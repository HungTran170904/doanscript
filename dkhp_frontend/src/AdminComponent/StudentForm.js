import { Col, Form, Row } from "react-bootstrap";

const StudentForm=({studentDTO})=>{
          function handleOnChange(e, fieldName){
                    if(fieldName.substring(0,5)==="user.") 
                              studentDTO.user[fieldName.slice(5)]=e.target.value;
                    else studentDTO[fieldName]=e.target.value;
          }
          return(
                    <Form>
                              <Row className="mb-3">
                                        <Form.Group as={Col} controlId="user.userId">
                                                  <Form.Label>MSSV</Form.Label>
                                                  <Form.Control type="text" onChange={(e)=>handleOnChange(e,"user.userId")}/>
                                        </Form.Group>
                                        <Form.Group as={Col} controlId="user.name">
                                                  <Form.Label>Họ Tên</Form.Label>
                                                  <Form.Control type="text" onChange={(e)=>handleOnChange(e,"user.name")}/>
                                        </Form.Group>
                              </Row>
                              <Row className="mb-3">
                                        <Form.Group as={Col} controlId="user.email">
                                                  <Form.Label>Email</Form.Label>
                                                  <Form.Control type="email" onChange={(e)=>handleOnChange(e,"user.email")}/>
                                        </Form.Group>
                                        <Form.Group as={Col} controlId="user.password">
                                                  <Form.Label>Password</Form.Label>
                                                  <Form.Control type="password" onChange={(e)=>handleOnChange(e,"user.password")}/>
                                        </Form.Group>
                              </Row>
                              <Row className="mb-3">
                                        <Form.Group as={Col} sm={4} controlId="falcutyName">
                                                  <Form.Label>Khoa</Form.Label>
                                                  <Form.Control type="text" onChange={(e)=>handleOnChange(e,"falcutyName")}/>
                                        </Form.Group>
                                        <Form.Group as={Col} sm={5} controlId="program">
                                                  <Form.Label>Ngành</Form.Label>
                                                  <Form.Control type="text" onChange={(e)=>handleOnChange(e,"program")}/>
                                        </Form.Group>
                                        <Form.Group as={Col} sm={3} controlId="khoaTuyen">
                                                  <Form.Label>Khóa tuyển</Form.Label>
                                                  <Form.Control type="text" onChange={(e)=>handleOnChange(e,"khoaTuyen")} required/>
                                        </Form.Group>
                              </Row>
                    </Form>
          )
}
export default StudentForm;